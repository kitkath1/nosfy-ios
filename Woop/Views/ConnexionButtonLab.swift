import SwiftUI

// MARK: - Banc d'essai (`-buttonLab`)

/// Page noire nue : rien que le bouton CONNEXION, pour le régler au pixel.
struct ConnexionButtonLab: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            DiamondConnexionButton {}
                .padding(.horizontal, 26)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Bouton

/// « CONNEXION » — un bijou d'obsidienne. Tout l'écrin (fumée noire qui
/// dérive, liseré hairline à accents inégaux qui respire, halos débordants,
/// poussières-particules) vit dans DiamondButton.metal ; ici, seulement le
/// texte en dégradé de blanc et la flèche.
struct DiamondConnexionButton: View {
    var action: () -> Void = {}

    /// Marge de débordement : halos et particules vivent hors du bouton.
    private static let pad: CGFloat = 34

    var body: some View {
        Button(action: action) {
            content
                .frame(height: 58)
                .frame(maxWidth: .infinity)
                .background { ecrin }
        }
        .buttonStyle(.plain)
    }

    /// L'hôte du shader, agrandi de `pad` de chaque côté — le rendu hors du
    /// bouton n'existe qu'en alpha (halos, particules), jamais en aplat.
    private var ecrin: some View {
        GeometryReader { geo in
            let w = geo.size.width + Self.pad * 2
            let h = geo.size.height + Self.pad * 2
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(ShaderLibrary.diamondButton(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)), .float(19)))
            }
            .offset(x: -Self.pad, y: -Self.pad)
        }
        .allowsHitTesting(false)
    }

    // MARK: Texte

    private var content: some View {
        Text("CONNEXION")
            .font(.system(size: 13.5, weight: .medium))
            .tracking(4.6)
            .padding(.leading, 4.6)
            .foregroundStyle(LinearGradient(stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white.opacity(0.86), location: 0.45),
                .init(color: .white.opacity(0.54), location: 1.0)
            ], startPoint: .top, endPoint: .bottom))
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.trailing, 22)
            }
    }
}

#Preview {
    ConnexionButtonLab()
}
