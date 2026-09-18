import SwiftUI

// MARK: - Banc d'essai (`-buttonLab`)

/// Page noire nue : l'input (vide en haut, actif au milieu) et le bouton
/// CONNEXION, pour les régler au pixel.
struct ConnexionButtonLab: View {
    @State private var emptyText = ""
    @State private var filledText = "kathryn@gmail.com"

    /// DÉTOUR PROVISOIRE — le banc du slider obsidienne se prend ici, en
    /// `-buttonLab -sliderLab`, parce que `WoopApp.swift` (le vrai routeur)
    /// était en cours d'édition par une autre session le 21-08. Dès qu'il
    /// refroidit, `-sliderLab` doit devenir une route racine comme les
    /// trente-cinq autres, et ces quatre lignes disparaissent.
    private static let sliderLab = CommandLine.arguments.contains("-sliderLab")

    var body: some View {
        if Self.sliderLab { SliderLab() } else { corps }
    }

    private var corps: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                // Le retour, à sa place naturelle : en tête, côté gauche.
                HStack {
                    DiamondBackButton {}
                    Spacer()
                }
                DiamondInputField(placeholder: "Adresse email", text: $emptyText)
                DiamondInputField(placeholder: "Adresse email", text: $filledText)
                DiamondConnexionButton {}
                // La copie en état « tap » permanent : pour régler l'éveil
                // de l'écrin au pixel, sans devoir garder le doigt posé.
                DiamondConnexionButton(benchPress: 1) {}
                DiamondSecondaryButton(title: "CRÉER UN COMPTE") {}
                // La copie du secondary en tap : la fumée d'éveil, figée
                // pour le réglage au pixel.
                DiamondSecondaryButton(title: "CRÉER UN COMPTE", benchPress: 1) {}
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
    /// Le clavier appelé. L'email est le défaut historique ; la connexion
    /// demande un numéro, et un pavé numérique sur un champ de téléphone n'est
    /// pas un détail — c'est la moitié du confort de saisie.
    var keyboard: UIKeyboardType = .emailAddress

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
                    .keyboardType(keyboard)
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

/// LE BOUTON PRIMAIRE DU SYSTÈME — depuis le 30-08, une COQUILLE : il rend
/// `BoutonPrimaire` (le bouton NOIR, `BoutonPrimaire.swift`) et garde son API,
/// donc les douze sites (porte, coffre, sheets, booster, Progress…) l'ont pris
/// sans qu'une ligne ne bouge. Le bijou d'obsidienne au shader — un
/// `colorEffect` à 30 Hz en permanence, mesuré 60 → 16 img/s au sim sur la
/// page Progress — est mort avec son verdict (« trop cheap »). Le shader
/// `diamondButton` reste dans DiamondButton.metal, plus appelé.
struct DiamondPrimaryButton: View {
    var title: String = "CONNEXION"
    var glyph: String? = nil
    var benchPress: Float? = nil
    var smokeWarmth: Float = 0
    var action: () -> Void = {}

    var body: some View {
        BoutonPrimaire(title: title, glyph: glyph, benchPress: benchPress,
                       smokeWarmth: smokeWarmth, action: action)
    }
}

/// Le réglage d'origine du composant : le CTA de l'auth.
typealias DiamondConnexionButton = DiamondPrimaryButton

// MARK: - Bouton retour (rond, verre liquide)

/// Le bouton icône rond du système (retour, fermetures) : un disque de
/// Liquid Glass NATIF — le fond se réfracte dedans — serti d'un anneau
/// hairline imparfait (`diamondRing`) qui murmure, chevron en dégradé blanc.
struct DiamondBackButton: View {
    var icon: String = "chevron.left"
    var action: () -> Void = {}

    private static let size: CGFloat = 46
    /// Marge du shader : le souffle de l'anneau est minuscule.
    private static let pad: CGFloat = 10

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(LinearGradient(
                    colors: [.white.opacity(0.95), .white.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: Self.size, height: Self.size)
                .glassEffect(.regular.tint(.black.opacity(0.45)).interactive(),
                             in: Circle())
                .overlay { ring }
        }
        .buttonStyle(.plain)
    }

    private var ring: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = Float(tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900))
            let side = Self.size + Self.pad * 2
            Rectangle()
                .fill(.white)
                .frame(width: side, height: side)
                .colorEffect(ShaderLibrary.diamondRing(
                    .float2(side, side), .float(t), .float(Float(Self.pad))))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Bouton secondaire

/// Le second rôle sous le primaire : noir profond (ni métal, ni fumée — une
/// profondeur calme), liseré discret imparfait à peine animé
/// (`diamondSecondary`), texte en retrait du CONNEXION.
struct DiamondSecondaryButton: View {
    let title: String
    /// Le banc force l'état tap ; nil = interaction réelle.
    var benchPress: Float? = nil
    var action: () -> Void = {}

    /// Marge large : la fumée d'éveil s'échappe AUTOUR du bouton au tap.
    private static let pad: CGFloat = 30

    /// Même rampe que le primaire : 0,30 s à l'allumage, 0,55 s au relâcher.
    @State private var pressEdge: Date = .distantPast
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            // La casse des boutons (30-08) : une phrase, comme le primaire.
            Text(title.enPhrase)
                .font(.system(size: 13.5, weight: .medium))
                .tracking(4.6)
                .padding(.leading, 4.6)
                .foregroundStyle(LinearGradient(stops: [
                    .init(color: .white.opacity(0.78), location: 0.0),
                    .init(color: .white.opacity(0.62), location: 0.45),
                    .init(color: .white.opacity(0.40), location: 1.0)
                ], startPoint: .top, endPoint: .bottom))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background { ecrin }
        }
        .buttonStyle(DiamondPressStyle { p in
            guard p != isPressed else { return }
            pressEdge = .now
            isPressed = p
        })
    }

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
                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(ShaderLibrary.diamondSecondary(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)), .float(19),
                        .float(press)))
            }
            .offset(x: -Self.pad, y: -Self.pad)
        }
        .allowsHitTesting(false)
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
