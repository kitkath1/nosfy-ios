import SwiftUI

// MARK: - Atmosphère

/// Moteur d'atmosphère : une nappe de brume et un champ de poussière, dessinés
/// dans un seul `Canvas`.
///
/// Les deux vivent dans le même contexte parce qu'ils se protègent mutuellement.
/// La poussière fait office de bruit bleu sur le dégradé de brume et casse le
/// banding ; la brume donne à la poussière un volume dans lequel flotter.
/// Séparées en deux vues, on paie deux couches de composition et on perd les
/// deux bénéfices.
///
/// Aucun état stocké : le générateur est réamorcé à la même constante à chaque
/// image et le temps n'entre que par des fonctions fermées. Le champ est donc
/// reproductible image après image, sans dérive accumulée — c'est ce qui permet
/// de mettre l'animation en pause et de la reprendre sans le moindre saut.
struct WoopAtmosphere: View {

    // MARK: Réglages

    /// Un banc de brume. Volontairement plus large que la surface : on n'en voit
    /// jamais qu'un flanc, donc l'œil lit « la lumière se déplace » et non « une
    /// bulle traverse l'écran ». C'est toute la différence entre brume et blob.
    struct Bank {
        /// Période de dérive, en secondes. Longue = luxe.
        var period: Double
        var phase: Double
        /// Largeur et hauteur, en fraction de la surface.
        var width: Double
        var height: Double
        /// Hauteur de repos du banc, en fraction. La brume est basse : le haut
        /// des cartes porte le texte et le biseau, il doit rester net.
        var anchor: Double
        var alpha: Double
        var tint: Color
    }

    /// Une bande de profondeur du champ de poussière. Trois bandes à des
    /// vitesses différentes : c'est la parallaxe qui fait le volume. Une seule
    /// vitesse et le champ redevient une texture qui défile.
    struct DustBand {
        var count: Int
        /// Vitesse d'ascension, en points par seconde.
        var speed: Double
        var rMin: Double
        var rMax: Double
        var aMin: Double
        var aMax: Double
    }

    struct Tuning {
        /// Cadence de rendu. Jamais 120 : aux vitesses employées ici le
        /// déplacement par image est très inférieur au pixel, donc monter la
        /// cadence ne change rien à l'œil et double la consommation.
        var fps: Double
        var banks: [Bank]
        var dust: [DustBand]
        /// Alpha maximal attendu. Sert à répartir les grains en paliers
        /// d'opacité : on dessine un chemin par palier au lieu d'un chemin par
        /// grain. Doit rester ≥ au plus grand `aMax`, sinon le palier haut écrase.
        var dustPeak: Double
        /// Atténuation de la poussière vers le bas. Reprend le comportement du
        /// champ d'origine : la profondeur vient de là autant que de la vitesse.
        var dustDepthFade: Double
        /// Proportion de grains violets. Au-delà de ~0,2 le champ bascule dans
        /// le registre « halo IA » — le violet est un assaisonnement, pas une teinte.
        var tintedRatio: Double
    }

    var tuning: Tuning
    var paused: Bool = false

    // MARK: Corps

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / tuning.fps, paused: paused)) { timeline in
            // Époque fixe soustraite plutôt qu'un `@State` de départ : un état
            // de départ se réinitialise dès que SwiftUI recrée la vue, et
            // l'animation saute. Ici le temps est absolu, donc continu quoi
            // qu'il arrive au cycle de vie de la vue.
            // Époque fixe soustraite : le temps reste petit, donc la précision
            // Double reste franche. Aucune quantification par cadence — la version
            // précédente figeait le temps par paliers de 5 s dès que la cadence
            // n'était pas `.live`, ce qui est le cas en permanence au simulateur.
            // `minimumInterval` suffit à réguler la fréquence de rendu.
            let t = timeline.date.timeIntervalSinceReferenceDate - 780_000_000

            Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { ctx, size in
                drawBanks(&ctx, size: size, t: t)
                drawDust(&ctx, size: size, t: t)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Brume

    /// Ce qui empêche un banc de lire « tache grise floue » :
    /// 1. il est plus large que la surface, donc sans centre visible ;
    /// 2. son dégradé a cinq arrêts — une rampe linéaire à deux arrêts EST un blob ;
    /// 3. il est écrasé en hauteur, parce que la brume est stratifiée, pas sphérique ;
    /// 4. les périodes sont premières entre elles, donc la composition ne boucle jamais ;
    /// 5. on compose en `plusLighter` : on ajoute de la lumière au noir, on ne le grise jamais.
    private func drawBanks(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        guard size.width > 1, size.height > 1 else { return }

        // Copie du contexte : le mode de fusion ne s'applique qu'aux tracés qui
        // passent par elle. Aucun `drawLayer`, donc aucune passe hors écran.
        var mist = ctx
        mist.blendMode = .plusLighter

        for bank in tuning.banks {
            let u = t / bank.period + bank.phase

            // Dérive horizontale modeste. Le banc débordant largement, un quart
            // de largeur suffit à faire glisser tout son flanc sur la surface.
            let cx = (0.5 + 0.24 * sin(u * 2 * .pi)) * size.width
            // Nombre d'or entre les deux axes : la trajectoire est une Lissajous
            // ouverte, jamais une ellipse qui se referme.
            let cy = (bank.anchor + 0.10 * sin(u * 2 * .pi * 1.618 + bank.phase)) * size.height

            // Respiration très lente du volume. Sans elle le banc glisse comme
            // un décor peint ; avec elle il a l'air d'un gaz.
            let breathe = 1 + 0.14 * sin(u * 2 * .pi * 0.41 + bank.phase * 1.7)

            let rx = max(1, bank.width * size.width * 0.5 * breathe)
            let ry = max(1, bank.height * size.height * 0.5 * breathe)

            // Modulation d'intensité désynchronisée de la position : la densité
            // varie sans que la carte entière ne respire en clair/sombre.
            let a = bank.alpha * (0.78 + 0.22 * sin(u * 2 * .pi * 0.63 + bank.phase))

            let falloff = Gradient(stops: [
                .init(color: bank.tint.opacity(a), location: 0.0),
                .init(color: bank.tint.opacity(a * 0.52), location: 0.28),
                .init(color: bank.tint.opacity(a * 0.24), location: 0.52),
                .init(color: bank.tint.opacity(a * 0.07), location: 0.76),
                .init(color: bank.tint.opacity(0), location: 1.0)
            ])

            // Anisotropie : un disque tracé dans un repère écrasé en hauteur.
            // Le dégradé suit l'écrasement, donc aucune couture.
            var strat = mist
            strat.translateBy(x: cx, y: cy)
            strat.scaleBy(x: 1, y: ry / rx)
            strat.fill(
                Path(ellipseIn: CGRect(x: -rx, y: -rx, width: rx * 2, height: rx * 2)),
                with: .radialGradient(falloff, center: .zero,
                                      startRadius: 0, endRadius: rx,
                                      options: .linearColor)
            )
        }
    }

    // MARK: Poussière

    /// Règle absolue de ce champ : le temps ne module que des POSITIONS, jamais
    /// des opacités. Une opacité qui bat, c'est du scintillement, et du
    /// scintillement c'est un gadget. Chaque grain garde donc sa luminosité à
    /// vie et se contente de dériver et d'osciller.
    private func drawDust(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        guard size.width > 1, size.height > 1 else { return }

        // Même générateur congruentiel que le champ d'origine, réamorcé à la
        // même constante : les caractéristiques de chaque grain sont identiques
        // d'une image à l'autre, sans stocker un seul octet.
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double((seed >> 33) % 100_000) / 100_000
        }

        var dust = ctx
        dust.blendMode = .plusLighter

        // Un chemin par palier d'opacité plutôt qu'un tracé par grain : quelques
        // remplissages par image au lieu de plusieurs centaines. C'est la
        // différence entre « indétectable » et « visible dans Instruments ».
        // Douze paliers, pas six : le fondu de bord fait descendre un grain le
        // long de l'échelle, et avec un pas trop large on le verrait sauter de
        // luminosité tous les quelques secondes — soit exactement le
        // scintillement qu'on s'interdit.
        let levels = 12
        var pale = [Path](repeating: Path(), count: levels)
        var tinted = [Path](repeating: Path(), count: levels)

        // Les grains naissent et meurent hors cadre : rien n'apparaît en plein
        // milieu, rien n'est tranché net par le bord.
        let margin = 14.0
        let spanW = size.width + margin * 2
        let spanH = size.height + margin * 2

        for band in tuning.dust {
            for _ in 0..<band.count {
                let x0 = next() * spanW
                let y0 = next() * spanH
                let radius = band.rMin + next() * (band.rMax - band.rMin)
                let alpha0 = band.aMin + next() * (band.aMax - band.aMin)

                // Oscillation propre à chaque grain, longue et de faible
                // amplitude. Sans elle, les trois bandes défilent en bloc et le
                // champ redevient une texture qui glisse.
                let swayAmp = 1.2 + next() * 2.8
                let swayPeriod = 16 + next() * 26
                let swayPhase = next() * 2 * .pi
                let isTinted = next() > (1 - tuning.tintedRatio)

                var x = (x0 + swayAmp * sin(t * 2 * .pi / swayPeriod + swayPhase))
                    .truncatingRemainder(dividingBy: spanW)
                if x < 0 { x += spanW }
                x -= margin

                // Ascension : la poussière monte, comme dans un rai de lumière.
                var y = (y0 - t * band.speed).truncatingRemainder(dividingBy: spanH)
                if y < 0 { y += spanH }
                y -= margin

                // Fondu de bord en plus du rognage : un grain qui se rematérialise
                // net à la lisière est le détail qui trahit le procédé.
                let fadeX = min(x + margin, size.width + margin - x) / 22
                let fadeY = min(y + margin, size.height + margin - y) / 20
                let edge = max(0, min(1, min(fadeX, fadeY)))

                let depth = 1 - (y / size.height) * tuning.dustDepthFade
                let alpha = alpha0 * edge * max(0, depth)
                if alpha < 0.004 { continue }

                let rect = CGRect(x: x - radius, y: y - radius,
                                  width: radius * 2, height: radius * 2)
                let bucket = min(levels - 1, max(0, Int(alpha / tuning.dustPeak * Double(levels))))
                if isTinted {
                    tinted[bucket].addEllipse(in: rect)
                } else {
                    pale[bucket].addEllipse(in: rect)
                }
            }
        }

        for level in 0..<levels {
            let alpha = (Double(level) + 0.5) / Double(levels) * tuning.dustPeak
            if !pale[level].isEmpty {
                dust.fill(pale[level], with: .color(.white.opacity(alpha)))
            }
            if !tinted[level].isEmpty {
                dust.fill(tinted[level], with: .color(.woopViolet.opacity(alpha * 1.3)))
            }
        }
    }
}

// MARK: - Réglages types

extension WoopAtmosphere.Tuning {

    /// Carte hebdomadaire. Surface petite et regardée de près : grains plus
    /// denses et un peu plus contrastés, brume un cran plus présente puisqu'elle
    /// se pose sur du métal et non sur du noir. Les bancs sont ancrés bas —
    /// c'est derrière les cinq ronds que la matière doit bouger, pas derrière
    /// le grand chiffre, dont le contraste ne se négocie pas.
    static let card = WoopAtmosphere.Tuning(
        fps: 24,
        banks: [
            .init(period: 97, phase: 0.00, width: 1.50, height: 0.62,
                  anchor: 0.62, alpha: 0.050,
                  tint: Color(red: 0.62, green: 0.64, blue: 0.73)),
            .init(period: 131, phase: 2.70, width: 1.15, height: 0.46,
                  anchor: 0.78, alpha: 0.038,
                  tint: Color(red: 0.72, green: 0.72, blue: 0.76)),
            .init(period: 179, phase: 5.20, width: 1.80, height: 0.55,
                  anchor: 0.90, alpha: 0.012, tint: .woopVioletDeep)
        ],
        dust: [
            .init(count: 70, speed: 0.9, rMin: 0.26, rMax: 0.44, aMin: 0.05, aMax: 0.11),
            .init(count: 44, speed: 1.9, rMin: 0.38, rMax: 0.62, aMin: 0.09, aMax: 0.18),
            .init(count: 20, speed: 3.4, rMin: 0.55, rMax: 0.92, aMin: 0.15, aMax: 0.28)
        ],
        dustPeak: 0.30,
        dustDepthFade: 0.30,
        tintedRatio: 0.14
    )
}

// MARK: - Grain

/// Tramage. Entre 0,016 et 0,125 la palette ne dispose que d'une trentaine de
/// valeurs codables en 8 bits : sans bruit, toute nappe douce se lit en anneaux
/// de Mach sur un OLED dans le noir, et c'est LE signal qui fait « bon marché ».
/// Un flou n'y change rien — on flouterait une image déjà quantifiée.
///
/// Deux populations, claire et sombre, en somme nulle : un grain uniquement
/// additif relèverait le plancher et grisirait le noir. Statique, parce qu'un
/// grain qui bouge est de la neige de télévision.
struct WoopGrain: View {
    /// Grains par point carré.
    var density: Double = 0.035
    var lightAlpha: Double = 0.030
    var darkAlpha: Double = 0.040

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { ctx, size in
            var seed: UInt64 = 0x2545_F491_4F6C_DD1D
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double((seed >> 33) % 100_000) / 100_000
            }

            let count = Int(size.width * size.height * density)
            // Deux chemins, deux remplissages. Un remplissage par grain coûterait
            // plusieurs dizaines de millisecondes à la première mise en page.
            var light = Path()
            var dark = Path()
            // 0,7 pt ≈ 2 px sur un écran ×3 : assez fin pour rester du bruit,
            // assez large pour ne pas être avalé par l'antialiasing.
            let side = 0.7

            for _ in 0..<count {
                let x = next() * size.width
                let y = next() * size.height
                let rect = CGRect(x: x, y: y, width: side, height: side)
                if next() > 0.5 {
                    light.addRect(rect)
                } else {
                    dark.addRect(rect)
                }
            }

            ctx.fill(light, with: .color(.white.opacity(lightAlpha)))
            ctx.fill(dark, with: .color(.black.opacity(darkAlpha)))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Fond global

/// Le fond n'est jamais uniformément noir : une voûte de nuages gris-noir, une
/// nébuleuse blanche en bas à gauche et un champ d'étoiles lui donnent sa
/// profondeur (voir DemonSky.metal), un grain lui donne sa matière.
/// Volontairement achromatique — un halo violet ferait « interface IA » et
/// écraserait le métal.
///
/// `animated` est faux par défaut, et c'est délibéré : ce fond est instancié
/// dans une douzaine d'écrans, dont des feuilles posées par-dessus un autre
/// fond. N'animer que l'écran d'accueil garde le coût permanent à une seule
/// instance, et l'image figée est rigoureusement la même composition.
struct WoopBackground: View {
    var animated: Bool = false
    /// Décalage de scroll du contenu, pour la parallaxe du ciel (home).
    var scroll: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Pas de garde sur `scenePhase` : `TimelineView` cesse déjà de se déclencher
    // quand l'app passe en arrière-plan, et la garde s'est révélée gelée en
    // permanence à l'exécution (vérifié au simulateur, fenêtre au premier plan).
    private var paused: Bool { !animated || reduceMotion }

    var body: some View {
        WoopDemonSky(paused: paused, scroll: scroll)
            // Le grain passe en dernier : il trame le ciel, dont les nappes les
            // plus sombres bandent au moins autant que l'ancienne brume.
            .overlay { WoopGrain() }
            .clipped()
            .ignoresSafeArea()
    }
}

// MARK: - Surface métal brumeuse

/// `metalSurface`, mais avec l'atmosphère glissée ENTRE le métal et le reflet
/// spéculaire. L'ordre n'est pas un détail : au-dessus du spéculaire la brume a
/// l'air de flotter devant la carte, en dessous elle est dans la matière. Mêmes
/// pixels, lecture complètement différente.
///
/// Réservé à la carte hebdomadaire. Une app dont toutes les surfaces respirent
/// n'a plus de hiérarchie, et l'effet cesse d'être un privilège.
struct MistyMetalSurface: ViewModifier {
    var cornerRadius: CGFloat = 24
    var neon: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var onScreen = true

    // Même raison que pour le fond : la garde `scenePhase` gelait l'animation.
    // La sortie d'écran suffit à couper le coût quand la carte n'est plus visible.
    private var paused: Bool { !onScreen || reduceMotion }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background {
                ZStack {
                    // L'ombre portée est accrochée au SEUL calque qui ne change
                    // jamais. Sur le groupe entier, Core Animation recalculerait
                    // un flou de rayon 22 à chaque image de l'atmosphère : c'est
                    // de loin le poste le plus cher de tout l'effet, et il est
                    // évitable pour rien.
                    shape.fill(WoopGradient.metal)
                        .compositingGroup()
                        .shadow(color: .black.opacity(0.75), radius: 22, y: 14)
                        .shadow(color: neon ? Color.woopVioletCore.opacity(0.14) : .clear,
                                radius: 24, y: 6)

                    WoopAtmosphere(tuning: .card, paused: paused)
                        .clipShape(shape)

                    WoopGrain(density: 0.05, lightAlpha: 0.028, darkAlpha: 0.036)
                        .clipShape(shape)

                    shape.fill(WoopGradient.specular)
                }
            }
            .overlay {
                shape.strokeBorder(neon ? WoopGradient.bevelNeon : WoopGradient.bevel,
                                   lineWidth: 1)
            }
            // Une carte sortie de l'écran qui continue d'animer est du courant
            // dépensé pour personne. Hors ScrollView le rappel ne se déclenche
            // pas et la valeur reste à `true` : dégradation sans risque.
            .onScrollVisibilityChange(threshold: 0.02) { visible in
                onScreen = visible
            }
    }
}

extension View {
    func mistyMetalSurface(cornerRadius: CGFloat = 24, neon: Bool = false) -> some View {
        modifier(MistyMetalSurface(cornerRadius: cornerRadius, neon: neon))
    }
}