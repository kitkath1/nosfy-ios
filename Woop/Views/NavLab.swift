import SwiftUI

// MARK: - Banc d'essai de la barre d'onglets bijou (`-navLab`)

// Le composant lui-même vit dans Woop/Views/JewelTabBar.swift ; ici, seulement
// la page nue et le panneau de fouettage.

/// Page nue : la barre seule, en bas, et le panneau de fouettage. On n'itère
/// JAMAIS dans l'app réelle — la home met dix secondes à revenir et on perd le
/// fil de l'œil.
struct NavLab: View {
    /// Les quatre onglets réels de l'app.
    private static let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Accueil"),
        ("figure.strengthtraining.functional", "Exercices"),
        ("chart.line.uptrend.xyaxis", "Progrès"),
        ("calendar", "Calendrier"),
    ]

    @State private var selection = 0
    @State private var params = JewelParams()
    @State private var showPanel = true
    /// La référence est posée sur un gris #141414, pas sur du noir pur : sur
    /// noir pur, l'ombre portée disparaît et la pierre perd son détachement.
    @State private var greyPage = true

    var body: some View {
        ZStack {
            (greyPage ? Color(red: 0.078, green: 0.078, blue: 0.082) : Color.black)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showPanel { panel } else { Spacer(minLength: 0) }

                JewelTabBar(items: Self.tabs, selection: $selection, params: params)
                    .frame(height: 64)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onTapGesture(count: 2) { showPanel.toggle() }
    }

    private var panel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("FIL DE MÉTAL LIQUIDE")
                        .font(.inter(10, .semibold))
                        .tracking(2.0)
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    Button(greyPage ? "gris" : "noir") { greyPage.toggle() }
                        .font(.inter(11))
                        .foregroundStyle(Color.inkSecondary)
                    Button("défauts") { params = JewelParams() }
                        .font(.inter(11))
                        .foregroundStyle(Color.inkSecondary)
                }
                .padding(.bottom, 8)

                row("contour", $params.contour, 0, 1)
                row("repetition", $params.repetition, 0.2, 6)
                row("floor", $params.floorLevel, 0, 0.6)
                row("softness", $params.softness, 0.005, 0.9)
                row("shiftRed", $params.shiftRed, 0, 0.20)
                row("shiftBlue", $params.shiftBlue, 0, 0.20)
                row("distortion", $params.distortion, 0, 1)
                row("angle", $params.angle, 0, 360)
                row("speed", $params.speed, 0, 1.5)
                row("influence", $params.influence, 1, 20)
                row("lineW", $params.lineW, 0.4, 5)
                row("gold", $params.gold, 0, 1)
                row("glow", $params.glow, 0, 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ name: String, _ value: Binding<Double>,
                     _ lo: Double, _ hi: Double) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.inter(11))
                .foregroundStyle(Color.inkMuted)
                .frame(width: 78, alignment: .leading)
            Slider(value: value, in: lo...hi)
                .tint(Color.woopGold)
            Text(String(format: abs(hi) > 20 ? "%.0f" : "%.3f", value.wrappedValue))
                .font(.inter(10).monospacedDigit())
                .foregroundStyle(Color.inkSecondary)
                .frame(width: 46, alignment: .trailing)
        }
        .frame(height: 26)
    }
}
