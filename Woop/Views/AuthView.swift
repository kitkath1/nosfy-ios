import SwiftUI

// MARK: - Écran d'authentification

/// L'écran qui suit le splash. Le fond est la photo de nébuleuse elle-même
/// (AuthNight, 852×1846), STRICTEMENT FIXE, rendue vivante par les couches
/// procédurales de `LivingNebulaBackground` — la veine respire, les grains
/// dérivent le long des filaments, la brume masque et révèle — puis par
/// `DevilAuraOverlay` : le liseré-diamant des sphères, leurs mèches, leur
/// fumée noire, et des yeux qui vivent. Au centre, le formulaire.
struct AuthView: View {
    var onConnect: (String) -> Void

    /// L'horloge de la scène : posée à l'apparition.
    @State private var start: Date?
    @State private var formShown = false
    @State private var phone = ""
    @State private var connecting = false
    @FocusState private var phoneFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var digits: String { phone.filter(\.isNumber) }
    /// Un mobile français : dix chiffres, 06 ou 07.
    private var isValid: Bool {
        digits.count == 10 && (digits.hasPrefix("06") || digits.hasPrefix("07"))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TimelineView(.animation(minimumInterval: NebulaConfig.frameInterval)) { context in
                let t = start.map { context.date.timeIntervalSince($0) } ?? 0
                let tilt = reduceMotion ? CGVector.zero : SkyMotion.shared.tilt
                ZStack {
                    LivingNebulaBackground(t: t, tilt: tilt)
                    DevilAuraOverlay(t: t, tilt: tilt)
                }
            }
            .ignoresSafeArea()
            .onTapGesture { phoneFocused = false }

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    Text("Bienvenue")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Ton numéro suffit — tes séances\nte retrouvent partout.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.inkSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.bottom, 34)
                .reveal(formShown, delay: 0)

                phoneField
                    .padding(.bottom, 16)
                    .reveal(formShown, delay: 0.12)

                Button {
                    connect()
                } label: {
                    Text("Se connecter par SMS")
                }
                .buttonStyle(WoopPrimaryButtonStyle())
                .disabled(!isValid || connecting)
                .opacity(isValid ? 1 : 0.45)
                .animation(.easeOut(duration: 0.25), value: isValid)
                .reveal(formShown, delay: 0.24)

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            start = Date()
            // La parallaxe gyroscopique : la même dérive de caméra que le ciel
            // de la home — mais elle ne touche QUE les couches procédurales,
            // l'image, elle, reste immobile au pixel.
            SkyMotion.shared.start(reduceMotion: reduceMotion)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { formShown = true }
        }
    }

    /// La connexion est immédiate : un toucher, on entre. Le vrai envoi d'OTP
    /// viendra se loger ici plus tard.
    private func connect() {
        guard !connecting else { return }
        connecting = true
        phoneFocused = false
        onConnect(digits)
    }

    // MARK: Formulaire

    private var phoneField: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.inkMuted)
            TextField("06 12 34 56 78", text: $phone)
                .keyboardType(.numberPad)
                .textContentType(.telephoneNumber)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .tint(Color.inkPrimary)
                .focused($phoneFocused)
                .onChange(of: phone) { _, value in
                    let formatted = Self.format(value)
                    if formatted != value { phone = formatted }
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.055))
        }
        .overlay {
            // La même arête de lumière que le bouton velours : vive en haut,
            // morte en bas — et qui s'éveille quand le champ prend le focus.
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(phoneFocused ? 0.55 : 0.28), location: 0.0),
                            .init(color: .white.opacity(0.07), location: 0.4),
                            .init(color: .white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .animation(.easeOut(duration: 0.3), value: phoneFocused)
    }

    /// « 0612345678 » → « 06 12 34 56 78 » — dix chiffres, groupés par deux.
    private static func format(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber).prefix(10)
        var out = ""
        for (i, d) in digits.enumerated() {
            if i > 0 && i % 2 == 0 { out.append(" ") }
            out.append(d)
        }
        return out
    }
}

// MARK: - Révélation du formulaire

private extension View {
    /// L'entrée d'un bloc du formulaire : il monte de 26 pt en fondu, avec son
    /// retard propre — la cascade dans la nuit.
    func reveal(_ shown: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 26)
            .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(delay),
                       value: shown)
    }
}
