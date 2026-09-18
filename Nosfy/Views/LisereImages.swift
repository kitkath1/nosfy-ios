import SwiftUI

/// `-lisereImages` : respiration et transactions entièrement SwiftUI.
/// Trois images natives remplacent la peinture et les traits floutés ;
/// les rotations et l'opacité de pression restent animées par l'hôte.
/// Le cache appartient à cette instance, jamais à une table globale.
@MainActor
struct LisereImages<F: Shape, Repli: View>: View {
    var forme: F
    var W: CGFloat
    var H: CGFloat
    var chambre: Double
    var penche: Double
    var phase: Double
    var dort: Bool
    var armer: () -> Void
    @ViewBuilder var repli: () -> Repli

    @Environment(\.displayScale) private var displayScale
    @State private var cache: LisereImagesCache?

    var body: some View {
        let cle = LisereImagesCle(
            taille: CGSize(width: W, height: H),
            scale: max(displayScale, 1),
            chemin: forme.path(in: CGRect(x: 0, y: 0, width: W, height: H)))
        Group {
            if let cache, cache.cle == cle, let images = cache.images {
                dessiner(images, cle: cle)
                    .task(id: dort) {
                        guard !Task.isCancelled else { return }
                        // Les effets de rotation viennent d'être montés :
                        // armer ici évite de perdre le souffle lorsque les
                        // images remplacent le repli après le premier rendu.
                        armer()
                    }
            } else {
                repli()
                    .task(id: dort) {
                        guard !Task.isCancelled else { return }
                        armer()
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: cle) {
            guard !Task.isCancelled, cache?.cle != cle else { return }
            // Seule cette task cuit les images, sur le MainActor.
            // La clé exclut phase, chambre, penche et visibilité.
            let images = LisereImagesDessin.rendre(forme: forme, cle: cle)
            guard !Task.isCancelled else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                cache = LisereImagesCache(cle: cle, images: images)
            }
            if images == nil {
                print("[lisere] Images indisponibles : retour au témoin SwiftUI")
            }
        }
    }

    private func dessiner(_ images: LisereImagesContenu,
                          cle: LisereImagesCle) -> some View {
        let cote = hypot(W, H)
        let cotePeinture = cote * sqrt(2)
        let marge = LisereImagesDessin.marge
        return Image(decorative: images.peinture, scale: cle.scale)
            .resizable()
            .frame(width: cotePeinture, height: cotePeinture)
            // L'angle de base tourne la peinture DANS le carré d'origine.
            .rotationEffect(.degrees(16 * chambre - penche))
            .frame(width: cote, height: cote)
            .clipped()
            // La respiration seule tourne ensuite ce carré.
            .rotationEffect(.degrees(phase))
            .frame(width: W, height: H)
            .mask {
                ZStack {
                    Image(decorative: images.masque, scale: cle.scale)
                        .resizable()
                    Image(decorative: images.pression, scale: cle.scale)
                        .resizable()
                        .opacity(0.55 * chambre)
                }
                .frame(width: W + 2 * marge, height: H + 2 * marge)
                .frame(width: W, height: H)
            }
    }
}

private struct LisereImagesCle: Equatable {
    var taille: CGSize
    var scale: CGFloat
    var chemin: Path
}

private struct LisereImagesContenu {
    var peinture: CGImage
    var masque: CGImage
    var pression: CGImage
}

private struct LisereImagesCache {
    var cle: LisereImagesCle
    // Mémoriser aussi un échec évite de relancer ImageRenderer en boucle.
    var images: LisereImagesContenu?
}

@MainActor
private enum LisereImagesDessin {
    static let marge: CGFloat = 16

    static func rendre<F: Shape>(forme: F,
                                cle: LisereImagesCle) -> LisereImagesContenu? {
        let W = cle.taille.width, H = cle.taille.height
        guard W > 0, H > 0, W.isFinite, H.isFinite,
              cle.scale > 0, cle.scale.isFinite else { return nil }
        let cotePeinture = hypot(W, H) * sqrt(2)
        let peinture = Rectangle()
            .fill(cardLisereConique(.zero))
            .frame(width: cotePeinture, height: cotePeinture)
        // Les deux couches constantes sont fusionnées dans leur ordre
        // source-over. La troisième garde une opacité SwiftUI animable :
        // alpha final = base + (1 - base) * pression * 0.55 * chambre.
        let masque = ZStack {
            forme.stroke(.white, lineWidth: 1.6)
            forme.stroke(.white, lineWidth: 4.4)
                .blur(radius: 2.4)
                .opacity(0.46)
        }
        .frame(width: W, height: H)
        .padding(marge)
        let pression = forme.stroke(.white, lineWidth: 2.6)
            .blur(radius: 1.2)
            .frame(width: W, height: H)
            .padding(marge)
        guard let couleur = image(peinture, scale: cle.scale),
              let base = image(masque, scale: cle.scale),
              let appui = image(pression, scale: cle.scale) else { return nil }
        return LisereImagesContenu(peinture: couleur, masque: base,
                                  pression: appui)
    }

    private static func image<V: View>(_ contenu: V,
                                      scale: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: contenu)
        renderer.scale = scale
        renderer.isOpaque = false
        renderer.colorMode = .nonLinear
        // Même export que le prototype natif ; aucune conversion couleur
        // ou fichier intermédiaire. Le renderer n'est pas retenu.
        return renderer.cgImage
    }
}
