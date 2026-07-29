import SwiftUI

// MARK: - Banc d'essai (`-buttonLab`)

/// Page noire nue : l'input (vide en haut, actif au milieu) et le bouton
/// CONNEXION, pour les régler au pixel.
struct ConnexionButtonLab: View {
    @State private var emptyText = ""
    @State private var filledText = "kathryn@gmail.com"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                DiamondInputField(placeholder: "Adresse email", text: $emptyText)
                DiamondInputField(placeholder: "Adresse email", text: $filledText)
                DiamondConnexionButton {}
                // La copie en état « tap » permanent : pour régler l'éveil
                // de l'écrin au pixel, sans devoir garder le doigt posé.
                DiamondConnexionButton(benchPress: 1) {}
            }
            .padding(.horizontal, 26)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Input

/// Le champ de saisie « diamant » — le petit frère sobre du bouton : métal
/// noir qui brille à peine, hairline à quelques accents scintillants, PAS de
/// fumée (l'écrin vit dans `diamondInput`, DiamondButton.metal). Vide : le
/// placeholder murmure en dégradé blanc foncé ; actif (focus ou texte), la
/// saisie parle en dégradé blanc clair, comme le bouton.
struct DiamondInputField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = "envelope"

    @FocusState private var focused: Bool

    /// Marge de débordement du shader : le souffle des accents est minuscule.
    private static let pad: CGFloat = 14

    private var active: Bool { focused || !text.isEmpty }

    /// La lumière d'éveil s'anime à la main : un paramètre de shader ne
    /// s'interpole pas tout seul — on horodate le basculement et le
    /// TimelineView fait la rampe (0,45 s, lissée).
    @State private var animStart: Date = .distantPast
    @State private var wasActive = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(LinearGradient(stops: [
                            .init(color: .white.opacity(0.62), location: 0.0),
                            .init(color: .white.opacity(0.34), location: 1.0)
                        ], startPoint: .top, endPoint: .bottom))
                }
                TextField("", text: $text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(LinearGradient(stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: .white.opacity(0.86), location: 0.45),
                        .init(color: .white.opacity(0.58), location: 1.0)
                    ], startPoint: .top, endPoint: .bottom))
                    .tint(Color.white.opacity(0.75))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
            }
            Image(systemName: icon)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(LinearGradient(
                    colors: [.white.opacity(0.92), .white.opacity(0.48)],
                    startPoint: .top, endPoint: .bottom))
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .background { ecrin }
        .animation(.easeOut(duration: 0.25), value: active)
        .onAppear { wasActive = active }
        .onChange(of: active) { _, now in
            animStart = .now
            wasActive = now
        }
    }

    private var ecrin: some View {
        GeometryReader { geo in
            let w = geo.size.width + Self.pad * 2
            let h = geo.size.height + Self.pad * 2
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                let raw = min(max(tl.date.timeIntervalSince(animStart) / 0.45, 0), 1)
                let eased = Float(raw * raw * (3 - 2 * raw))
                let wake = wasActive ? eased : 1 - eased
                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(ShaderLibrary.diamondInput(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)), .float(17), .float(wake)))
            }
            .offset(x: -Self.pad, y: -Self.pad)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Bouton

/// « CONNEXION » — un bijou d'obsidienne. Tout l'écrin (fumée noire qui
/// dérive, liseré hairline à accents inégaux qui respire, halos débordants,
/// poussières-particules) vit dans DiamondButton.metal ; ici, seulement le
/// texte en dégradé de blanc et la flèche.
struct DiamondConnexionButton: View {
    /// Le banc force l'état tap (1 = pressé en continu) ; nil = interaction
    /// réelle, l'écrin suit le doigt.
    var benchPress: Float? = nil
    var action: () -> Void = {}

    /// Marge de débordement : halos et particules vivent hors du bouton.
    private static let pad: CGFloat = 34

    /// La transition du tap s'anime à la main (un paramètre de shader ne
    /// s'interpole pas seul) : on horodate le contact et le TimelineView
    /// fait la rampe — 0,30 s à l'allumage, 0,55 s au relâcher — plus
    /// l'onde du toucher qui s'évase en ~0,3 s.
    @State private var pressEdge: Date = .distantPast
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            content
                .frame(height: 58)
                .frame(maxWidth: .infinity)
                .background { ecrin }
        }
        .buttonStyle(DiamondPressStyle { p in
            guard p != isPressed else { return }
            pressEdge = .now
            isPressed = p
        })
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
                let since = tl.date.timeIntervalSince(pressEdge)
                let raw = min(max(since / (isPressed ? 0.30 : 0.55), 0), 1)
                let eased = Float(raw * raw * (3 - 2 * raw))
                let press = benchPress ?? (isPressed ? eased : 1 - eased)
                let burst = (benchPress == nil && isPressed)
                    ? Float(exp(-since / 0.30)) : 0
                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(ShaderLibrary.diamondButton(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)), .float(19),
                        .float(press), .float(burst)))
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

/// Republie `isPressed` vers l'écrin et tasse imperceptiblement le bouton
/// sous le doigt — l'objet a un poids, jamais un simple changement d'opacité.
private struct DiamondPressStyle: ButtonStyle {
    var onPress: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.spring(duration: 0.32), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, v in onPress(v) }
    }
}

#Preview {
    ConnexionButtonLab()
}
