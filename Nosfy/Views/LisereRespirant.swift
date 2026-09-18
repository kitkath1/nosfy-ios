import SwiftUI

// MARK: - LE LISERÉ QUI RESPIRE (05-09)
//
// LE GESTE ① du plan `tools/nav/PLAN-DEBUG-PERF.md`, et la réponse à sa
// question : « c'est quand même possible d'optimiser sans perdre les vidéos
// et tout, on est en 2026 ? »
//
// CE QUI SE PASSAIT (WidgetsCards.swift, et le même motif partout) :
//   vingt fois par seconde —
//     · un dégradé CONIQUE recalculé,
//     · dessiné en TROIS traits superposés,
//     · dont DEUX FLOUTÉS (gaussiennes de 2,4 et 1,2),
//     · le tout sous un `GlassEffectContainer` + un verre natif,
//   pour faire tourner la lumière de ±3° sur 9,4 secondes.
// Trois degrés. Et le verre posé dessus ne peut RIEN mettre en cache,
// puisque ce qu'il y a dessous vient de changer.
//
// Le chemin SwiftUI anime une rotation, mais la trace du 15-09 montre
// encore AnimatableAttribute/DisplayList par image : cela ne prouve PAS
// une peinture mise en cache. Le prototype `-lisereCoreAnimation` rend
// explicitement ses images une fois par taille/forme/échelle, puis confie
// la rotation à Core Animation. Le témoin SwiftUI reste le défaut.
//
// ⚠️ POURQUOI ON TOURNE LA PEINTURE ET PAS LE DESSIN. Faire tourner la vue
// de 3° ferait tourner LE CADRE DE LA CARD — parfaitement visible. Ce qui
// doit tourner, c'est la LUMIÈRE sur le contour, pas le contour. D'où :
// un carré de dégradé plus grand que la card, qu'on tourne, et le contour
// (traits + flous) posé en MASQUE par-dessus. Le masque, lui, ne bouge
// jamais : il est construit une fois.
//
// ⚠️ CE QUI CHANGE À L'ŒIL, dit honnêtement : le flou s'applique désormais
// à l'ALPHA du trait au lieu de s'appliquer au trait DÉJÀ peint. Sur ce
// dégradé-ci la différence est arithmétiquement négligeable — 2,4 pt de
// flou couvrent environ 0,4° d'arc, quand l'épaule la plus raide du
// dégradé s'étale sur 7° (`cardLisereStops`). Mais « négligeable » n'est
// pas « nul » : c'est à elle de trancher sur capture, pas à moi.
//
// ⚠️ LE PIÈGE, DÉJÀ PAYÉ (`PageCard.swift`) : un `repeatForever` posé par
// `withAnimation` SE FAIT AVALER quand le parent est ré-évalué. La phase
// vit donc ICI, dans la feuille, et se ré-arme à `.task`.

/// `-souffleHorloge` : rejoue l'ANCIENNE forme (la `TimelineView` qui
/// redessine). C'est le témoin de l'A/B, et le chemin de retour si le
/// rendu ne lui convient pas.
enum SouffleBanc {
    static let horloge = CommandLine.arguments.contains("-souffleHorloge")
}

/// A/B du liseré seulement. `-liserePose <degrés>` fige la composante de
/// respiration sur les deux chemins (la pression et penche s'y ajoutent).
/// Le témoin est LisereRespirant SwiftUI, sans `-souffleHorloge`.
enum LisereAnimationBanc {
    static let images = CommandLine.arguments.contains("-lisereImages")
    static let coreAnimation = CommandLine.arguments
        .contains("-lisereCoreAnimation")
    static let pose: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-liserePose"),
              args.indices.contains(i + 1),
              let angle = Double(args[i + 1]), angle.isFinite
        else { return nil }
        return angle
    }()
}

struct LisereRespirant<F: Shape>: View {
    @Environment(\.decorHomeAuRepos) private var decorAuRepos
    var forme: F
    var W: CGFloat
    var H: CGFloat
    /// L'état de la card (pression) — il ne dépend PAS du temps : quand il
    /// change, une reconstruction est normale et rare.
    var chambre: Double
    var penche: Double
    /// Reduce Motion : la lumière se pose et ne bouge plus.
    var immobile: Bool
    /// L'amplitude et la période d'origine, au degré et à la seconde près.
    var amplitude: Double = 3.0
    var periode: Double = 9.4

    /// LA PHASE — la seule chose qui bouge. `@State` dans la FEUILLE :
    /// aucun parent ne peut avaler son animation.
    @State private var phase: Double = 0
    @State private var monte = false
    @State private var prototypeDisponible = true

    private var dort: Bool {
        immobile || decorAuRepos || !monte || ProtectionThermique.shared.ambianceAuRepos
    }

    var body: some View {
        Group {
            if LisereAnimationBanc.images {
                LisereImages(forme: forme, W: W, H: H,
                             chambre: chambre, penche: penche,
                             phase: LisereAnimationBanc.pose ?? phase,
                             dort: dort || LisereAnimationBanc.pose != nil,
                             armer: {
                                armer(dort || LisereAnimationBanc.pose != nil)
                             }) {
                    peinture
                        .frame(width: W, height: H)
                        .mask { masque }
                }
            } else if LisereAnimationBanc.coreAnimation, prototypeDisponible {
                LisereCoreAnimation(forme: forme, W: W, H: H,
                                    chambre: chambre, penche: penche,
                                    dort: dort, amplitude: amplitude,
                                    periode: periode,
                                    pose: LisereAnimationBanc.pose,
                                    onEchec: { prototypeDisponible = false })
                    .frame(width: W, height: H)
                    .allowsHitTesting(false)
            } else {
                peinture
                    .frame(width: W, height: H)
                    .mask { masque }
                    .task(id: dort) {
                        guard !Task.isCancelled else { return }
                        armer(dort || LisereAnimationBanc.pose != nil)
                    }
            }
        }
        .onAppear { monte = true }
        .onDisappear {
            monte = false
            // Annuler la task seule ne retire pas le repeatForever.
            armer(true)
        }
    }

    /// LA PEINTURE — le dégradé conique tourné par SwiftUI (le témoin).
    /// Le carré est plus grand que la card (√2) : même tourné, il la
    /// couvre entièrement, donc aucun coin ne se vide.
    private var peinture: some View {
        let cote = sqrt(W * W + H * H)
        return Rectangle()
            .fill(cardLisereConique(.degrees(16 * chambre - penche)))
            .frame(width: cote, height: cote)
            .rotationEffect(.degrees(LisereAnimationBanc.pose ?? phase))
    }

    /// LE MASQUE — les trois traits et leurs deux gaussiennes. Il ne
    /// dépend que de `chambre`, mais SwiftUI peut encore recomposer ce
    /// masque pendant la rotation ; son cache n'est pas garanti.
    private var masque: some View {
        ZStack {
            forme.stroke(.white, lineWidth: 1.6)
            forme.stroke(.white, lineWidth: 4.4)
                .blur(radius: 2.4)
                .opacity(0.46)
            // LE CADRE S'ALLUME QUAND LA CHAMBRE SE FERME : ce qui
            // identifie l'objet ne bouge jamais, seul son intérieur
            // change — il devient PLUS présent.
            forme.stroke(.white, lineWidth: 2.6)
                .blur(radius: 1.2)
                .opacity(0.55 * chambre)
        }
        .frame(width: W, height: H)
    }

    /// Le souffle : un aller-retour adouci entre −A et +A sur une
    /// demi-période. `easeInOut` autoreversé est, à l'œil, le sinus
    /// d'origine — et il est interpolé par le rendu, donc plus lisse que
    /// les vingt échantillons par seconde d'avant.
    private func armer(_ dort: Bool) {
        guard !dort else {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { phase = 0 }
            return
        }
        phase = -amplitude
        withAnimation(.easeInOut(duration: periode / 2)
            .repeatForever(autoreverses: true)) {
            phase = amplitude
        }
    }
}
