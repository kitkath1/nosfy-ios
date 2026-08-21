import SwiftUI

// MARK: - Banc du slider obsidienne

/// `-sliderLab` — la page noire nue. Par défaut : trois poses figées côte à
/// côte plus un exemplaire vivant. Le simulateur ne drague pas — sans les
/// poses, une capture ne montre jamais que le repos.
///
/// Drapeaux :
///   `-sliderAuto`         UN exemplaire qui rejoue le geste en boucle
///                         (5,2 s : poussée, tenue, commit, retour) — c'est
///                         celui-là qu'on FILME, la poudre et l'onde ne
///                         existent que dans le mouvement
///   `-sliderUne`          un seul exemplaire, pour la mesure fine
///   `-sliderFreeze <p>`   fige sa pose, p ∈ [0,1]
///   `-sliderGrip <g>`     force la prise (gonflement + flèche), g ∈ [0,1]
///   `-sliderFond <l>`     luminance du fond, 0-255 (défaut 27 = celui de la
///                         référence — sur du noir pur l'ombre ne se lit pas)
///   `-sliderBraise`       allume la braise du déjà-poussé
///   `-sliderPoudreSeule`  coupe les micro-diamants
struct SliderLab: View {

    private static let auto = CommandLine.arguments.contains("-sliderAuto")
    private static let une = CommandLine.arguments.contains("-sliderUne")
    private static let braise = CommandLine.arguments.contains("-sliderBraise")
    private static let poudreSeule =
        CommandLine.arguments.contains("-sliderPoudreSeule")

    /// Idiome A : on lit `CommandLine.arguments`, JAMAIS `UserDefaults` — il
    /// partage son espace de clés avec les `@AppStorage` et se fait piéger
    /// par les valeurs persistées d'une session précédente.
    private static func nombre(_ cle: String, defaut: Double) -> Double {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: cle), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return defaut }
        return v
    }

    private static let pose = min(max(nombre("-sliderFreeze", defaut: 0), 0), 1)
    private static let grip = min(max(nombre("-sliderGrip", defaut: 0), 0), 1)
    private static let fond = nombre("-sliderFond", defaut: 27) / 255.0

    var body: some View {
        ZStack {
            // Le fond de la RÉFÉRENCE, pas du noir pur : son ombre portée
            // assombrit le sol de 41 %, et sur du noir absolu il n'y a rien
            // à assombrir — la capsule flotterait sans poids.
            Color(white: Self.fond).ignoresSafeArea()

            if Self.auto {
                slider(pose: nil, grip: nil, auto: true)
                    .padding(.horizontal, 24)
            } else if Self.une {
                slider(pose: CGFloat(Self.pose), grip: CGFloat(Self.grip),
                       auto: false)
                    .padding(.horizontal, 24)
            } else {
                // LA MISE EN PAGE DE LA HOME. Le slider n'a pas de longueur à
                // lui : il prend ce qu'on lui donne. Le régler « plus court »
                // n'a donc de sens que dans SA rangée — 24 pt de marge, le
                // galet du menu (62 pt), l'écart, puis le reste. Sur un
                // iPhone 17 Pro ça lui laisse ~280 pt au lieu des 354 du banc
                // pleine largeur, et c'est à CETTE longueur qu'il faut le
                // juger : le pouce y pèse 28 % de la piste au lieu de 23 %.
                VStack(spacing: 40) {
                    rangee("hauteur 68 — la cote d'origine", 68)
                    rangee("hauteur 62 — à fleur du galet", 62)
                    ligne("vivant, pleine largeur", nil, nil)
                }
                .padding(.horizontal, 24)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .task {
            // `GaletSlide` ne prépare jamais ses générateurs — il compte sur
            // sa page hôte. Hors de cette page, la main est MUETTE et
            // l'arpège ne sonne pas : le banc doit le faire lui-même.
            RocketHaptics.shared.prepare()
            Paillettes.shared.prepare()
        }
    }

    private func slider(pose: CGFloat?, grip: CGFloat?, auto: Bool,
                        hauteur: CGFloat = 68) -> SliderObsidienne {
        SliderObsidienne(label: "Start",
                         height: hauteur,
                         braise: Self.braise ? 0.016 : 0,
                         diamants: !Self.poudreSeule,
                         auto: auto,
                         pose: pose, poseGrip: grip)
    }

    /// La rangée de la home : le galet du menu, puis le slider dans ce qui
    /// reste. Le galet est un LEURRE — 62 pt, la cote de `MenuNappe` — il
    /// n'est là que pour tenir la place et donner l'échelle.
    @ViewBuilder
    private func rangee(_ titre: String, _ hauteur: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titre.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(2.2)
                .foregroundStyle(Color.white.opacity(0.26))
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06))
                    Circle().strokeBorder(Color.white.opacity(0.16),
                                          lineWidth: 1)
                    Image(systemName: "house")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.80))
                }
                .frame(width: 62, height: 62)
                slider(pose: nil, grip: nil, auto: true, hauteur: hauteur)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func ligne(_ titre: String, _ p: CGFloat?,
                       _ g: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titre.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(2.2)
                .foregroundStyle(Color.white.opacity(0.26))
            slider(pose: p, grip: g, auto: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
