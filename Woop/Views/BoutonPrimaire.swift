import SwiftUI

// MARK: - LE BOUTON PRIMAIRE NOIR (30-08)
//
// Sa demande, sur un screenshot d'inspiration (« Appliquer le thème ») : plus
// de capitales ; la forme et la taille du bouton « locked » du coffre (une
// capsule de 58, `CoffreV2.swift`) ; TOUT NOIR, avec des halos blanc-gris dans
// son bas — la lumière vient d'en dessous — et un effet au tap.
//
// Ce qu'il n'a plus, et c'est MESURÉ : ni shader, ni horloge. Le diamant
// tournait un `colorEffect` à 30 Hz en permanence (60 → 16 img/s au sim sur
// la page Progress). Ici tout est peint une fois ; seul l'appui anime, et il
// s'arrête net.
//
// Même API que `DiamondPrimaryButton` (title, glyph, benchPress, smokeWarmth,
// action) : le jour où il le remplace, aucun site d'appel ne bouge.

struct BoutonPrimaire: View {
    var title: String
    /// Un glyphe SF à gauche, dans une gouttière réservée (le texte reste
    /// centré).
    var glyph: String? = nil
    /// Le banc force l'appui (1 = pressé en continu) ; nil = le doigt.
    var benchPress: Float? = nil
    /// Gardé pour l'API du diamant (les sites l'envoient) — sans effet ici :
    /// la lumière de ce bouton est blanche, jamais dorée.
    var smokeWarmth: Float = 0
    var action: () -> Void = {}

    @State private var presse = false
    /// LA POUDRE DU TAP (v6, son verdict : « les diamants n'apparaissent
    /// qu'au tap, comme les cards ») : la poudre fine de la maison,
    /// `PoudreMini` — seize grains par salve, l'étoile-facette, la gravité,
    /// et l'horloge qui DORT dès qu'il n'y a plus rien à semer. Rien au repos.
    @State private var poudres: [SalveMini] = []

    static let hauteur: CGFloat = 58
    /// La poudre vit HORS du bouton : le canvas déborde d'autant.
    static let debord: CGFloat = 34
    /// Un blanc à peine froid — « blanc gris », pas de couleur.
    private static let lumiere = Color(red: 0.90, green: 0.90, blue: 0.95)

    var body: some View {
        Button(action: action) {
            corps
        }
        .buttonStyle(PresseStyle(onPress: { v in
            presse = v
            if v { semer() }
        }))
        .accessibilityLabel(title)
        // LE BANC : l'échantillon à appui forcé sème une salve toutes les
        // 1,1 s, pour que la poudre se voie en capture (le sim ne tape pas).
        .task(id: benchPress) {
            guard benchPress != nil else { return }
            while !Task.isCancelled {
                semer()
                try? await Task.sleep(for: .milliseconds(1100))
            }
        }
    }

    /// Quatre salves de poudre nées sur le bord bas, RESSERRÉES au centre
    /// (v7, « plus condensés ») — l'école de l'ardoise : elles s'oublient
    /// toutes seules au bout de 0,95 s.
    private func semer() {
        let w = largeurMesuree
        let y = Self.debord + Self.hauteur
        for x in [0.41, 0.47, 0.53, 0.59] {
            let s = SalveMini(t0: Date(),
                              x: Self.debord + CGFloat(x) * w,
                              y: y,
                              graine: Int.random(in: 0 ... 9999))
            poudres.append(s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                poudres.removeAll { $0.id == s.id }
            }
        }
    }

    /// La largeur du bouton, lue une fois posé (la poudre se sème dessus).
    @State private var largeurMesuree: CGFloat = 300

    /// L'appui, 0 → 1 : le banc le force, le doigt le donne.
    private var p: Double { Double(benchPress ?? (presse ? 1 : 0)) }

    private var corps: some View {
        ZStack {
            plaque
            halos
            texte
        }
        .frame(height: Self.hauteur)
        .frame(maxWidth: .infinity)
        .clipShape(Capsule())
        .overlay(rim)
        // LA POUDRE, hors du bouton — en frère, pas dans le clip ; le canvas
        // dort tant qu'aucune salve ne vit.
        .overlay {
            PoudreMini(salves: poudres)
                .padding(-Self.debord)
                .allowsHitTesting(false)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
            largeurMesuree = $0
        }
        .contentShape(Capsule())
        .animation(.spring(response: 0.28, dampingFraction: 0.70), value: p)
    }

    /// NOIR (v6, « beaucoup plus noir ») : la plaque EST le noir de la page ;
    /// seuls le liseré et la nappe du bas disent le bouton.
    private var plaque: some View {
        // v8, « un peu moins foncé et c'est parfait » : entre le noir pur
        // (v7) et la plaque de v6 — un souffle de gris en haut.
        Capsule().fill(LinearGradient(
            colors: [Color(white: 0.016), Color(white: 0.004)],
            startPoint: .top, endPoint: .bottom))
    }

    /// LA LUMIÈRE VIENT D'EN DESSOUS : deux nappes ancrées sous le bord bas —
    /// une large et sourde, un cœur plus serré — qui MONTENT et s'allument
    /// sous le doigt. Des ellipses aux bornes de la capsule : larges et
    /// courtes, comme une lampe posée sous l'objet.
    private var halos: some View {
        // v2 (son screenshot) : pas de point chaud — une nappe LARGE et
        // diffuse qui monte sur la moitié du bouton, un cœur à peine là.
        ZStack {
            Capsule().fill(EllipticalGradient(
                stops: [
                    .init(color: Self.lumiere.opacity(0.125 + 0.25 * p), location: 0),
                    .init(color: Self.lumiere.opacity(0.045 + 0.085 * p), location: 0.40),
                    .init(color: Self.lumiere.opacity(0.016), location: 0.78),
                    .init(color: .clear, location: 1)
                ],
                center: UnitPoint(x: 0.5, y: 1.10 - 0.18 * p),
                startRadiusFraction: 0, endRadiusFraction: 1.15))
            Capsule().fill(EllipticalGradient(
                colors: [Self.lumiere.opacity(0.065 + 0.18 * p), .clear],
                center: UnitPoint(x: 0.5, y: 1.02 - 0.12 * p),
                startRadiusFraction: 0, endRadiusFraction: 0.60))
        }
    }

    /// Le liseré : presque rien en haut, la lumière le prend par le bas.
    private var rim: some View {
        Capsule().strokeBorder(LinearGradient(
            colors: [.white.opacity(0.055), .white.opacity(0.17 + 0.24 * p)],
            startPoint: .top, endPoint: .bottom), lineWidth: 1)
    }

    /// Le mot, en minuscules, au corps du bouton « locked » — ni capitales,
    /// ni interlettrage, ni flèche. Blanc, avec un souffle à peine là (v6,
    /// « trop de néon ») qui ne monte qu'au tap.
    private var texte: some View {
        Text(title)
            .font(.inter(18, .semibold))
            .tracking(-0.2)
            .foregroundStyle(.white.opacity(0.96))
            .shadow(color: .white.opacity(0.16 + 0.30 * p), radius: 7)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, glyph == nil ? 24 : 52)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                if let glyph {
                    Image(systemName: glyph)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.leading, 22)
                }
            }
    }
}

/// L'APPUI A DU POIDS : le bouton se tasse d'un rien, la lumière monte
/// (publiée à la vue), et le doigt le sent — léger à la prise, doux au
/// lâcher. Jamais un simple changement d'opacité.
private struct PresseStyle: ButtonStyle {
    var onPress: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.30, dampingFraction: 0.72),
                       value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, v in
                onPress(v)
                UIImpactFeedbackGenerator(style: v ? .light : .soft)
                    .impactOccurred(intensity: v ? 0.7 : 0.5)
            }
    }
}

// MARK: - Le banc : `-boutonLab`

/// La page noire nue : le bouton au repos, sous le doigt (forcé), avec un
/// glyphe — et le diamant d'avant, pour comparer.
struct BoutonLab: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                BoutonPrimaire(title: "Appliquer le thème") {}
                BoutonPrimaire(title: "Voir dans le lecteur") {}
                // L'état « tap » permanent, pour régler la lumière au pixel.
                BoutonPrimaire(title: "Appliquer le thème", benchPress: 1) {}
                BoutonPrimaire(title: "Se connecter", glyph: "apple.logo") {}
                Text("par la coquille DiamondPrimaryButton — le même")
                    .font(.inter(12, .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 18)
                DiamondPrimaryButton(title: "Voir dans le lecteur") {}
                Spacer()
            }
            .padding(.horizontal, 26)
        }
    }
}

#Preview { BoutonLab() }
